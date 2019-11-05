/*
 * Copyright (c) 2019, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


/** --------------------------------------------------------------------------*
 * @brief provides column input iterator with nulls replaced with a specified value
 * @file iterator.cuh
 * 
 * The column input iterator is designed to be used as an input
 * iterator for thrust and cub.
 *
 * Usage:
 * auto iter = make_null_replacement_iterator(column, null_value);
 * 
 * The column input iterator returns only a scalar value of data at [id] or 
 * the null_replacement value passed while creating the iterator.
 * For non-null column, use 
 * auto iter = column.begin<Element>();
 * 
 * -------------------------------------------------------------------------**/

#pragma once

#include <cudf/cudf.h>
#include <cudf/column/column_device_view.cuh>
#include <cudf/utilities/error.hpp>
#include <cudf/utilities/type_dispatcher.hpp>
#include <thrust/iterator/iterator_adaptor.h>
#include <thrust/iterator/counting_iterator.h>
#include <thrust/iterator/transform_iterator.h>

namespace cudf {
namespace experimental {

/** -------------------------------------------------------------------------*
 * @brief value accessor of column with null bitmask
 * A unary functor returns scalar value at `id`.
 * `operator() (cudf::size_type id)` computes `element` and valid flag at `id`
 *
 * the return value for element `i` will return `column[i]`
 * if it is valid, or `null_replacement` if it is null.
 *
 * @tparam Element The type of elements in the column
 * -------------------------------------------------------------------------**/
template <typename Element>
struct value_accessor
{
  column_device_view const col;         ///< column view of column in device
  Element const null_replacement{};     ///< value returned when element is null

/** -------------------------------------------------------------------------*
 * @brief constructor
 * @param[in] _col column device view of cudf column
 * @param[in] null_replacement The value to return for null elements
 * -------------------------------------------------------------------------**/
  value_accessor(column_device_view const _col, Element null_val)
    : col{_col}, null_replacement{null_val}
  {
    // verify valid is non-null, otherwise, is_valid() will crash
    CUDF_EXPECTS(_col.nullable(), "Unexpected non-nullable column.");
  }

  CUDA_DEVICE_CALLABLE
  Element operator()(cudf::size_type i) const {
    return col.is_valid_nocheck(i) ?
      col.element<Element>(i) : null_replacement;
  }
};
} //namespace experimental


/**
 * @brief Constructs an iterator over a column's values that replaces null
 * elements with a specified value.
 *
 * Dereferencing the returned iterator for element `i` will return `column[i]`
 * if it is valid, or `null_replacement` if it is null.
 *
 * @tparam Element The type of elements in the column
 * @param column The column to iterate
 * @param null_replacement The value to return for null elements
 * @return auto Iterator that returns valid column elements, or a null
 * replacement value for null elements.
 */
template <typename Element>
auto make_null_replacement_iterator(column_device_view const column,
                                    Element const null_replacement = Element{0})
{
  return thrust::make_transform_iterator(
      thrust::counting_iterator<cudf::size_type>{0},
      experimental::value_accessor<Element>{column, null_replacement});
}

template <typename Element,
          typename Iterator_Index = thrust::counting_iterator<cudf::size_type>>
auto make_null_replacement_custom_index_iterator(
    column_device_view const column,
    Element const null_replacement = Element{0},
    Iterator_Index const it = Iterator_Index{0})
{
  return thrust::make_transform_iterator(
      it, experimental::value_accessor<Element>{column, null_replacement});
}

} //namespace cudf
